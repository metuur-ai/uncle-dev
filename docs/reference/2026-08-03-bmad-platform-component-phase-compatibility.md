# Research: uncle-dev phase flow vs BMAD — platform-level and component-level compatibility

**Date:** 2026-08-03
**Question:** How can uncle-dev's development-phase flow be made compatible with BMAD at the platform level and the component level?
**Sources:** `.devlocal/llms-full.txt` (4,229 lines — full BMAD documentation dump, read sequentially); uncle-dev skills/commands/hooks/config in this repo; five prior research docs in `.devlocal/research/`; `.uncle-dev/learns/`.
**Nature:** As-is documentation. Where an integration seam is named, it is named as an *observed structural fact* (what would have to line up), not as a recommendation.

---

## 0. Finding that reframes the question

The user's framing — "the balance between **Platform-level** and **Component-level**" — does **not** appear in the BMAD documentation that is present in this repo.

Scanning all 4,229 lines of `.devlocal/llms-full.txt`:

- No match for `platform-level` / `component-level` as a vocabulary pair.
- No match for `scale level`, no `Level 0`–`Level 4` numbered project-level system.
- The only scope distinction BMAD actually documents is **single-story direct build vs. multi-epic planned build**, expressed as a rule of thumb:
  > "Clear work can enter `bmad-build` directly. Larger initiatives … " (`llms-full.txt:4196-4200`)
  > "If you have multiple epics that could be implemented by different agents, you need architecture." (`llms-full.txt:202-ish, quoted at llms-full.txt:2853-2959`)
- Multi-epic / multi-agent conflict prevention is framed **purely as architecture-documentation coverage**, not as a formal level system (`llms-full.txt:2853-2959`, `3230-3302`).

So there are two possible readings, and they lead to different work:

1. **The vocabulary comes from an older BMAD (v5/v6 "BMM scale levels 0–4").** That version is not in this repo. If this is the intent, the source doc needs to be supplied before any mapping can be evidence-based.
2. **The vocabulary is the user's own abstraction** for BMAD's observed two-tier shape: a *project-wide, always-on* tier (kernel + architecture spine + PRD) versus a *per-unit, disposable* tier (spec → story → build run). This reading **is** supported by the docs, and everything below documents that tier split.

This document proceeds on reading (2), and flags reading (1) as an open question in §7.

---

## 0.5 Fixed constraint (user-stated, not negotiable)

**The `@spec` EARS annotation stays mandatory.** Any BMAD compatibility work must preserve it as-is:

- `@spec <ID>` remains required on every behavior entry point when the repo uses `docs/specs/` — `skills/uncle-dev-incremental-implementation/SKILL.md:227-249,251-260`.
- It stays on the **owner/entry point only, never on helpers** — `skills/uncle-dev-spec-annotations/SKILL.md:86-124`.
- The live enforcement layer stays armed: `hooks/spec-coherence-guard.sh:1-8` blocks Edit|Write citing an undefined `@spec` ID (exit 2) and blocks `git commit*` when `scanner/scan-spec-coherence.py` exits non-zero on ORPHAN.
- The traceability chain `HLD ──▶ LLD ──▶ EARS spec ──▶ Test ──▶ Code` (`skills/uncle-dev-spec-annotations/SKILL.md:10`) is therefore load-bearing and cannot be replaced by a BMAD-style status state machine.

**Consequences for the seams below:**

| Seam | Effect of the constraint |
|---|---|
| §4.3 — two ID universes | **Resolved in favour of `SEG-AREA-NNN` / `docs/specs/`.** That is the universe `@spec` and the scanner actually validate (regex `[A-Z][A-Z0-9-]*-[0-9]+`, `CLAUDE.md:44-46`). Any BMAD interop hangs off segments, not off `R-x.y`. |
| §3 — BMAD `SPEC.md` 5-field contract | Cannot *replace* `docs/specs/<segment>-specs.md`. At most it becomes an additional upstream input whose content is distilled **into** EARS spec IDs, which then get `@spec`-annotated as today. |
| §5 — BMAD per-story files & `stories.yaml` | Story-level status (`draft`/`ready-for-dev`/`in-progress`/`in-review`/`done`/`blocked`) may be adopted alongside, but it is **additive**: a story reaching `done` still requires its code to carry `@spec` and to survive the commit-time scan. |
| §4.2 — soft PRD seam | Unchanged. Anything added above the HLD (a `@prd`-style edge or `index.yaml` parent/child registry, per `.devlocal/research/2026-06-24-...:294-296`) is a **new, separate** annotation axis — it must not weaken, alias, or substitute for `@spec`. |
| §4.1 — platform tier | `uncle-dev-initiative-map` stubs still hand off to `/uncle-dev-spec`, which still lands in `docs/specs/`; the platform tier is a map, never a bypass around the annotated chain. |

Precedent for adding a parallel axis without touching `@spec`: `@debt <ceiling>, <upgrade>` already exists as an explicitly separate axis (`skills/uncle-dev-spec-annotations/SKILL.md:150-188`).

---

## 1. BMAD's actual two tiers (as documented)

### Tier A — durable, project-wide ("platform-level" in the user's terms)

| Artifact | Written by | Property | Line |
|---|---|---|---|
| `kernel.md` | `bmad-project-context` | **Loaded into every agent session.** Hard budget ~150–200 instructions, priority-ordered. Pruning test per line: "would removing this line change agent behavior?" | `llms-full.txt:3025-3027` |
| knowledge bundle (`index.md` + entries) | `bmad-project-context` | Loaded **on demand, never wholesale**. Each entry carries a `verified` / `generated` trust marker | `llms-full.txt:3027` |
| `ARCHITECTURE-SPINE.md` | `bmad-architecture` | Technical decisions made explicit; "the architecture spine is the premier ingest source" for project-context | `llms-full.txt:4179`, `3047-3049` |
| `prd.md` (+ `addendum.md`, `.memlog.md`) | `bmad-prd` | Product-wide requirements; three intents in one skill (Create / Update / Validate) | `llms-full.txt:4153,4157-4163` |

Both kernel and bundle live in the `project_knowledge` folder, default `docs/` (`llms-full.txt:3029`). `context.py` handles validation, indexing, staleness sweeps, repo maps and cross-project resolution **mechanically** — "no agent ever guesses at mechanical facts" (`llms-full.txt:3029`).

The `Audit` intent is explicitly anti-accretion: "context shrinks or holds, never accretes" (`llms-full.txt:3031-3037`).

Stated rationale (`llms-full.txt:2966-3007`):
- "LLM-generated context documents measurably degrade agent performance — lower correctness at higher cost."
- "Every line of always-loaded context is paid for in every session."
- "Wrong context is worse than no context."
- Deliberately excluded from the kernel: what the code already says, repo structure/file maps, overview/tour docs, ecosystem defaults, edit history, unverified inference presented as fact, user-facing docs, aspirational state (`llms-full.txt:2992-3001`).

### Tier B — per-unit, disposable ("component-level")

| Artifact | Written by | Property | Line |
|---|---|---|---|
| `SPEC.md` under `{output_folder}/specs/spec-{slug}/` | `bmad-spec` | "the only writer of `SPEC.md`". Kernel of five fields: **Why, Capabilities, Constraints, Non-goals, Success signal** | `llms-full.txt:4155,4165-4167` |
| `stories.yaml` | `bmad-spec` (optional) | Ordered story list for autonomous dispatch | `llms-full.txt:4166` |
| Epic files with `## Epic N:` / `### Story N.M:` headings | `bmad-create-epics-and-stories` | Parsed deterministically by `sprint_plan.py` into kebab-case keys — **not** LLM inference | `llms-full.txt:4180`, `3127-3130` |
| `sprint-status.yaml` | `bmad-sprint-planning` | Status tracking; advanced statuses never downgraded on re-merge | `llms-full.txt:4181`, `3127-3130` |
| `<spec-folder>/stories/<story-id>-*.md` | `bmad-build` / `bmad-build-auto` | One file per story, status-frontmattered state machine | `llms-full.txt:3382-3400` |

**The bridge between tiers is stated explicitly:** "Each document becomes context for the next phase. The PRD tells the architect what constraints matter. The architecture tells the dev agent which patterns to follow. Spec files give focused, complete context for implementation." (`llms-full.txt:4206-4208`), and "Decisions are born in `bmad-architecture`; they live in project-context." (`llms-full.txt:3047-3049`)

That is the balance the question is about: **Tier A is the always-loaded, budget-capped, audited layer; Tier B is the per-unit, discardable, machine-parsed layer; `bmad-project-context` is the pump that moves durable decisions from B into A.**

### 1.5 The two tiers as a picture

The platform/component split is a **context-budget** split before it is an organisational one. Tier A is paid for in every session; Tier B is paid for once and discarded.

```
   PLATFORM LEVEL  (Tier A — durable, always/on-demand loaded)
   ┌──────────────────────────────────────────────────────────┐
   │  kernel.md               ~150–200 instrs, EVERY session  │
   │  knowledge bundle        on demand, never wholesale      │
   │  ARCHITECTURE-SPINE.md   ADRs, layer boundaries          │
   │  prd.md                  product-wide requirements       │
   └──────────────────────────────────────────────────────────┘
          │                                              ▲
   shard  │  (only the slice a unit needs)               │  pump
          ▼                                              │
   ┌──────────────────────────────────────────────────────────┐
   │  SPEC.md        Why / Capabilities / Constraints /       │
   │                 Non-goals / Success signal               │
   │  stories.yaml            ordered dispatch list           │
   │  epics + sprint-status.yaml    parsed, not inferred      │
   │  stories/<story-id>-*.md       status state machine      │
   └──────────────────────────────────────────────────────────┘
   COMPONENT LEVEL  (Tier B — per-unit, disposable)
```

Two arrows, opposite directions, different mechanisms:

- **shard (A → B)** — context engineering. A component build never receives the whole platform spec, only the slice its story needs: "Spec files give focused, complete context for implementation" (`llms-full.txt:4206-4208`).
- **pump (B → A)** — `bmad-project-context`. A decision discovered during component work is promoted into the durable layer, subject to the anti-accretion audit: "context shrinks or holds, never accretes" (`llms-full.txt:3031-3037`).

Anything not on one of those two arrows is deliberately excluded from Tier A — repo structure, file maps, overview docs, aspirational state (`llms-full.txt:2992-3001`).

### 1.6 BMAD's on-disk layout (as documented)

```
<project-root>/
├── _bmad/                              # installed config — not artifacts
│   ├── config.toml                     # + config.user.toml (personal, gitignored)
│   ├── bmm/config.yaml
│   └── custom/                         # customization overlays
│       ├── config.toml
│       ├── bmad-agent-pm.toml          # per-agent overrides
│       ├── bmad-agent-dev.toml
│       └── company-glossary.md
│
├── docs/                               # ◀ project_knowledge — PLATFORM (Tier A)
│   ├── kernel.md                       #   always loaded, budget-capped
│   ├── index.md                        #   knowledge bundle index
│   ├── ARCHITECTURE-SPINE.md
│   └── prd.md
│
└── _bmad-output/                       # generated artifacts
    ├── planning-artifacts/
    ├── implementation-artifacts/
    └── specs/                          # ◀ COMPONENT (Tier B)
        └── spec-diffsettings-audit/    #   one folder per slug
            ├── SPEC.md
            ├── stories.yaml
            └── stories/
                └── <story-id>-*.md
```

Evidence: the three top-level artifact roots are listed together at `llms-full.txt:842-843`; `docs/` is the default `project_knowledge` folder (`llms-full.txt:3029`); `_bmad-output/specs/spec-diffsettings-audit/` and its `stories.yaml` are the worked example at `llms-full.txt:218,231`; per-story files at `llms-full.txt:3382-3400`; `_bmad/config.toml` at `llms-full.txt:718`, `_bmad/custom/` overlays at `llms-full.txt:438,522,789`.

Note the separation BMAD enforces on disk: **config** (`_bmad/`), **durable knowledge** (`docs/`), and **generated output** (`_bmad-output/`) are three different roots. Only the middle one is version-controlled knowledge; `_bmad-output/` is the disposable tier.

---

## 2. uncle-dev's phase flow as it exists today

Full evidence in §2 of the scout report; condensed here.

### Mode routing (governs everything)
`scripts/uncle-dev-detect-mode.sh:8-16` resolves `lid-ears` or `openspec` from `preferences.sdd_mode` → filesystem signals → default `lid-ears`. Every lifecycle skill opens with a Phase 0 that prints the mode (`skills/uncle-dev-spec-driven-development/SKILL.md:14-32`, `skills/uncle-dev-planning-and-task-breakdown/SKILL.md:11-24`, `skills/uncle-dev-next-task/SKILL.md:72-93`). Inactive branches are stripped at install time via `<!-- UNCLE_DEV:BRANCH:… -->` markers and `scripts/lib/split-skill-branch.sh` (`README.md:279`).

### Phase chain (lid-ears, this repo's active mode)

| Phase | Command | Skill | Output |
|---|---|---|---|
| DEFINE | `/uncle-dev-spec` | `uncle-dev-spec-driven-development` | `docs/hld/<slug>.md`, `docs/lld/<slug>.md`, `docs/ears/<slug>.md` (`R-x.y` IDs) — `SKILL.md:65-140` |
| DEFINE (arch) | `/uncle-dev-design-docs` | `uncle-dev-design-architecture-docs` | `docs/high-level-design.md`, `docs/llds/<segment>.md`, `docs/specs/<segment>-specs.md` (`SEG-AREA-NNN`), `docs/arrows/<segment>.md`, `docs/arrows/index.yaml` |
| PLAN | `/uncle-dev-plan` | `uncle-dev-planning-and-task-breakdown` | `docs/tasks/<slug>.md` — stories with `why:`, `acceptance: R-1.1`, `verify:`, `landed:` (`SKILL.md:40-69`) |
| BUILD (select) | `/uncle-dev-next-task` | `uncle-dev-next-task` | ready-set + `.devlocal/_locks/<change-id>/<story-id>.lock` |
| BUILD (do) | `/uncle-dev-build` | `uncle-dev-incremental-implementation` + `uncle-dev-test-driven-development` | source + tests + `@spec` annotations |
| VERIFY / REVIEW / SHIP | `/uncle-dev-test`, `/uncle-dev-review`, `/uncle-dev-ship` | per `CLAUDE.md:26-28` | — |

Gates that actually block:
- **Spec lock** — one exact question, then STOP (`uncle-dev-spec-driven-development/SKILL.md:150-156`).
- **Plan review** — human approval before stories are actionable (`uncle-dev-planning-and-task-breakdown/SKILL.md:360-370`).
- **Acknowledge gate** — pending `### D<N>` entries with `status: pending` in `openspec/acknowledge/<scope>.md` remove a story from the ready set (`uncle-dev-next-task/SKILL.md:49-68,284-294`). **openspec mode only.**
- **`spec-coherence-guard.sh`** — PreToolUse Edit|Write blocks unknown `@spec` IDs; on `git commit*` runs `scan-spec-coherence.py` and blocks on non-zero exit (`hooks/spec-coherence-guard.sh:1-8`).

### uncle-dev's "always-loaded" layer
- `AGENTS.md` hierarchy, governed by `uncle-dev-context-engineering`: thresholds <20k tokens = no node, 20–64k = create a 2–3k-token node, >64k = split (`SKILL.md:77-82`, `agents-md-guide.md:73-79`). Template sections: Purpose, Entry Points, Contracts & Invariants, Patterns, Anti-patterns, Related Context.
- Enforced by `CLAUDE.md:102-107` ("Code Context (always enforced)") and nudged by `hooks/check-agents-md.sh` on every Edit|Write.
- Root `CLAUDE.md` is the single root instruction file; root `AGENTS.md` is a stub pointer.

---

## 3. Tier-by-tier correspondence (what already lines up)

| BMAD concept | uncle-dev equivalent | Match quality |
|---|---|---|
| `kernel.md` — always-loaded, ~150–200-instruction budget, pruning test, `verified`/`generated` trust markers | Root `CLAUDE.md` + `AGENTS.md` hierarchy | **Partial.** Same *role*, no budget, no pruning test, no trust markers, no audit intent. `uncle-dev-context-engineering` has token thresholds for *when to create a node*, not a ceiling on always-loaded instructions. |
| knowledge bundle, on-demand, `index.md` sole entry point | `.uncle-dev/learns/` + `docs/` | **Weak.** `.uncle-dev/learns/` has **one file total** (`best-practices/durable-rules-go-to-tracked-files-not-memory-2026-05-30.md`) — no index, no trust frontmatter, no staleness sweep. |
| `context.py` — mechanical validation/indexing/staleness | `scan-spec-coherence.py` + `scripts/check-manifest.sh` | **Partial, different axis.** uncle-dev's scanner validates *spec↔code* coherence, not *context freshness*. |
| `ARCHITECTURE-SPINE.md` | `docs/high-level-design.md` + `docs/llds/<segment>.md` | **Strong.** uncle-dev is more granular (per-segment LLD). |
| `prd.md` | `docs/prd/<slug>.md` from `uncle-dev-grill` | **Strong at unit level, absent at program level** — see §4.1. |
| `SPEC.md` five-field kernel (Why / Capabilities / Constraints / Non-goals / Success signal) | `docs/ears/<slug>.md` `R-x.y` table + `docs/specs/<segment>-specs.md` `SEG-AREA-NNN` | **Different shape.** uncle-dev's spec is a requirement *table*; BMAD's is a five-field *contract*. uncle-dev has no single "Non-goals"/"Success signal" pair as mandatory fields. |
| `stories.yaml` (machine-dispatchable, ordered) | `docs/tasks/<slug>.md` (markdown checkboxes) / `openspec/changes/<id>/tasks.md` | **Same intent, different medium.** BMAD's is YAML parsed by `sprint_plan.py`; uncle-dev's is markdown parsed by the agent. |
| `sprint-status.yaml` + status floor rules | `- [ ]`/`- [x]` checkbox + `.devlocal/_locks/` | **Weak.** No status state machine, no "advanced statuses never downgraded", no `--dry-run` drift report. Prior research confirms `landed:` is documented in the plan skill but **does not exist anywhere else in the repo** (`.devlocal/research/2026-07-30-plan-spec-story-fields.md:63-81`). |
| `bmad-sprint-planning` readiness gate → `PASS`/`CONCERNS`/`FAIL` | `/uncle-dev-pre-mortem` + spec-lock question | **Partial.** uncle-dev's gate is a yes/no human question; BMAD's is a three-verdict machine assessment with severity-ordered findings each naming the fixing skill. |
| Retrospective verdict `accepted` / `accepted-with-open-items` / `rejected`, "a failing epic never closes as quietly accepted" | `/uncle-dev-wrap`, `/uncle-dev-knowledge-capture` | **Weak.** No epic-level verdict, no rejection on unfinished stories. |
| Three-layer config override (`*.user.toml` → `*.toml` → `customize.toml`) | `UNCLE_DEV_<KEY>` env → session-mode flag → `.agents/uncle-dev-setup.yaml` → default (`scripts/uncle-dev-config.sh:142-227`) | **Strong.** Same three-tier idea, already implemented. |
| Named agents wrapping skills (`bmad-agent-pm`, etc.) with fixed 8-step activation | `agents/uncle-dev-ag-code-reviewer`, `-test-engineer`, `-security-auditor` | **Partial.** uncle-dev has personas but no phase-anchored agent-per-phase roster and no menu-trigger codes. |

---

## 4. The three structural seams

### 4.1 There is no program/platform tier above the feature slug

Established by prior research and re-confirmed unchanged this session (`.devlocal/research/2026-06-24-cross-platform-master-prd-decomposition.md:138-163`):

- `uncle-dev-feature-map`, `uncle-dev-research`, `uncle-dev-brownfield` each read **one** codebase; no skill fans out across repos and merges into one impact map (`:143-146`).
- `uncle-dev-grill` produces **exactly one PRD per slug**; there is no master-PRD artifact linking child PRDs (`:148-151`).
- No formal parent→child sub-PRD relationship — "the linkage lives in your directory naming, not in tooling" (`:153-157`).
- Impact analysis (`spec-graph`) is **downstream of specs**, so it cannot answer "what would this impact" before specs exist (`:159-162`).

The one skill that reaches toward the platform tier is **`uncle-dev-initiative-map`** (`skills/uncle-dev-initiative-map/SKILL.md`). Its frontmatter explicitly covers "every impacted feature, capability, service, application, and component across repos/platforms", Phase 2 fans out parallel subagents per repo and reuses `.uncle-dev/feature-maps/*.md`, and it emits a tiered YAML tracker + a rendered map + one stub per big item. It stops deliberately: "It does **not** write specs, tasks, or code, and it does not run the heavy spec ceremony (no HLD/LLD/EARS, no pre-mortem)" (`SKILL.md:24-25`).

So the platform tier exists as a **map**, but the map's stubs are handed off by *name*, not by a tracked parent/child edge. `grep -rn "@prd" skills commands` returns nothing; no `parent`/`child` keys exist in `uncle-dev-initiative-map/SKILL.md`.

### 4.2 The enforcement boundary sits below the PRD tier

`.devlocal/research/2026-06-24-...:244-296` documents this precisely, and it still holds:

- **Machine-enforced:** HLD → LLD → EARS → Test → Code, via `@spec` annotations, `docs/arrows/index.yaml`, `/uncle-dev-spec-scan` (exits non-zero on ORPHAN) and the `spec-coherence-guard.sh` commit hook.
- **Soft seam:** master PRD → sub-PRD → HLD. The only connection is that `/uncle-dev-spec` does a one-time read of `docs/prd/<slug>.md` if present. "No `@spec`-equivalent links a PRD to its HLD/EARS, and `spec-scan` does not validate PRD→spec coherence" (`:270-273`).

BMAD has the mirror-image property: its **platform tier is the enforced one** (kernel budget, `context.py` audit, architecture-spine ingest) while its per-story tier is enforced by a *status state machine* rather than by traceability IDs. The two systems enforce at opposite ends of the same chain.

### 4.3 Two ID universes inside uncle-dev, neither of which is BMAD-shaped

Per `CLAUDE.md:44-46`:
1. `docs/hld/`, `docs/lld/`, `docs/ears/` with `R-x.y` IDs — coverage is a **manual check**, no scanner.
2. `docs/specs/<segment>-specs.md` with `SEG-AREA-NNN` IDs — **scanner-enforced** via regex `[A-Z][A-Z0-9-]*-[0-9]+`. The scanner is explicitly not extended to accept `R-x.y`.

Any BMAD interop has to pick one. Universe 2 (`SEG-AREA-NNN`, segment-scoped) is the structurally closer analogue to BMAD's per-spec-folder model, because a *segment* is already "one product-behavior area owned by one LLD" (`uncle-dev-design-architecture-docs/SKILL.md:47`) — which is what BMAD calls a spec folder.

---

## 5. Where the two flows would meet, phase by phase

Purely a correspondence table — no claim that any of these are implemented.

| BMAD phase | BMAD workflows | uncle-dev phase | uncle-dev skills | Meeting point |
|---|---|---|---|---|
| 1. Analysis (optional) | `bmad-brainstorming`, `bmad-forge-idea`, `bmad-deep-recon`, `bmad-product-brief`, `bmad-prfaq` | Define | `uncle-dev-idea-refine`, `uncle-dev-verbalized-sampling`, `uncle-dev-research`, `uncle-dev-grill` | Output of BMAD's `brief.md` / `research.md` = input slot of `/uncle-dev-grill` |
| 2. Planning | `bmad-prd`, `bmad-ux`, `bmad-spec` | Define | `uncle-dev-grill` → `docs/prd/<slug>.md`; `uncle-dev-spec-driven-development` | BMAD `SPEC.md` five-field contract ≈ the *input* `/uncle-dev-spec` expects, not its output |
| 3. Solutioning | `bmad-architecture`, `bmad-create-epics-and-stories`, `bmad-sprint-planning` | Define(arch) + Plan | `uncle-dev-design-architecture-docs`, `uncle-dev-planning-and-task-breakdown` | `ARCHITECTURE-SPINE.md` ≈ `docs/high-level-design.md`; epics/stories ≈ `docs/tasks/<slug>.md` |
| 4. Implementation | `bmad-build`, `bmad-build-auto`, `bmad-code-review`, `bmad-correct-course`, `bmad-retrospective` | Build + Verify + Review | `uncle-dev-next-task`, `uncle-dev-incremental-implementation`, `uncle-dev-test-driven-development`, `uncle-dev-code-review-and-quality` | Story dispatch: BMAD folder+ID vs uncle-dev ready-set+lock |
| (cross-cutting) | `bmad-project-context` (kernel + bundle) | — | `uncle-dev-context-engineering` (`AGENTS.md`) + `.uncle-dev/learns/` | **The largest structural difference** — see §3 row 1–3 |
| (cross-cutting) | `bmad-customize` three-layer TOML | — | `scripts/uncle-dev-config.sh` four-tier resolution | Already equivalent |

Notable one-way asymmetries:

- BMAD's `bmad-build-auto` dispatches **exactly one `stories.yaml` entry per invocation** (`llms-full.txt:3400`) and, during planning, loads every sibling `stories/*.md` so stories see each other's Code Map, Design Notes, Spec Change Log and Auto Run Result (`llms-full.txt:3398`). uncle-dev's `next-task` computes a ready set with tie-breakers (most descendants → resumes scratchpad → smallest est → document order, `SKILL.md:126-131`) but does **not** cross-load sibling story state; per-story context lives in `.devlocal/<user>/<story-id>/scratchpad.md`, which is private and gitignored.
- BMAD's blocked-story rule is permanent ("delete the file to retry", `llms-full.txt:3382-3400`) with 13 enumerated blocking conditions (`llms-full.txt:3471-3485`). uncle-dev has no blocked state — only locked/unlocked.
- uncle-dev has a **live PreToolUse enforcement layer** (14 hooks in `hooks/hooks.json`) that BMAD's documentation does not describe an equivalent of; BMAD enforces in-workflow, uncle-dev enforces at tool-call time.

---

## 6. Prior art — do not re-derive

| Doc | What it already settles |
|---|---|
| `.devlocal/research/2026-06-24-cross-platform-master-prd-decomposition.md` | **Load-bearing.** Segment (not repo/platform) is the decomposition primitive; no cross-repo aggregator; PRD tier sits above the enforcement boundary. Closing proposal — a `@prd`-style annotation or an `index.yaml` parent/child registry so `spec-scan`/`spec-graph` can reach above the HLD (`:294-296`) — **unimplemented**. |
| `.devlocal/research/2026-07-30-wayfinder-vs-uncle-dev-spec-build.md` | Six gaps in the *pre-spec* funnel, none closed: no computed frontier at pre-spec tier, no claiming/concurrency above story level, decisions tracked with inverted polarity (`uncle-dev-acknowledge` records already-made decisions, openspec-mode only), free-text `## Open Questions` with "no id, no status, no owner, no resolution transition, and no downstream consumer" and "no graduation rule anywhere" (`:194,230-231`), out-of-scope as static list not transition, no session budgeting at pre-spec tier. Nearest analogue to BMAD's story-level context isolation. |
| `.devlocal/research/2026-07-30-plan-spec-story-fields.md` | `why:`/`acceptance:`/`verify:` are real per-story keys; **`landed:` does not exist anywhere in the repo** — completion is the `- [ ]`→`- [x]` checkbox. Any BMAD-style status state machine must compose with the checkbox model. |
| `.devlocal/research/2026-06-16-improving-uncle-dev-with-ponytail-patterns.md` | Item 9 + the "per-turn full-ruleset injection" boundary note (`:135`) is the **existing** discussion of always-loaded vs on-demand — it documents why uncle-dev deliberately avoids ponytail's always-on full-ruleset injection (corpus too large). Directly relevant before importing BMAD's kernel concept. Items 1, 2, 4, 5 now implemented (`scripts/check-manifest.sh`, `skills/uncle-dev-over-engineering-audit/`, `commands/uncle-dev-debt.md`, `commands/uncle-dev-mode.md`). |
| `.devlocal/research/2026-06-17-upstream-0.5.0-to-0.6.2-gap-analysis.md` | Only #2 (observability) implemented. #1 security expansion, #3 doubt-driven-development, #4 web-performance-auditor, #5 frontend Space-key a11y still open. #6 `/build auto` is a **deliberate** non-implementation — `uncle-dev-incremental-implementation` rejects one-pass builds by design. This matters: BMAD's `bmad-build-auto` is exactly the pattern uncle-dev has already decided against. |
| `.uncle-dev/learns/` | One file only: `best-practices/durable-rules-go-to-tracked-files-not-memory-2026-05-30.md` — durable rules go to tracked files, never private memory. Nothing about scoping, sharding, kernels, or gates. No knowledge-capture entries added since 2026-06-17. |

---

## 7. Open questions

1. **Which BMAD is meant?** The "Platform-level / Component-level" pair is not in `.devlocal/llms-full.txt`. If it comes from BMAD v5/v6 BMM scale levels 0–4, that source is not in this repo and must be supplied before any level-mapping can be evidence-based.
2. ~~**Which ID universe hosts the interop?**~~ **Closed** by §0.5 — `@spec` stays mandatory, so the interop hangs off the scanner-enforced `SEG-AREA-NNN` / `docs/specs/` universe. `R-x.y` remains the manual-check track and gains nothing from BMAD. Residual sub-question: whether the per-feature `docs/ears/<slug>.md` track should be *promoted* into `docs/specs/<segment>-specs.md` during BMAD interop, or left as the parallel manual track it is today (`CLAUDE.md:44-46`).
3. **Does `uncle-dev-initiative-map`'s tiered YAML tracker already carry enough structure to serve as the platform-tier registry**, or does the parent/child edge proposed in the 2026-06-24 doc still need to be added? Not determined this session — the tracker schema was not read past the SKILL.md's Phase 1–3 description.
4. **`bmad-build-auto` interop is blocked by a standing design decision.** uncle-dev has explicitly rejected one-pass autonomous builds (2026-06-17 doc, item #6). Any BMAD Phase-4 compatibility must either respect that or reopen it as a product decision.
5. **Kernel budget vs. uncle-dev's skill corpus.** BMAD's ~150–200-instruction always-loaded ceiling is incompatible on its face with uncle-dev's current root `CLAUDE.md` + 45-skill corpus; the ponytail doc already documents why uncle-dev routes on-demand instead. Whether a *separate* budget-capped kernel could sit alongside the existing `AGENTS.md` hierarchy was not investigated.

---

## 8. Key file references

**BMAD source:** `.devlocal/llms-full.txt` — phases `:4108-4208`; agents `:2618-2649`, `:3304-3325`; project-context/kernel `:2961-3056`; sprint-planning gate `:3110-3148`; build-auto dispatch `:3334-3555`; customization `:434-823`.

**uncle-dev:**
- `scripts/uncle-dev-detect-mode.sh:8-16` — mode resolution
- `scripts/uncle-dev-config.sh:142-227` — four-tier config resolution (sole reader of `.agents/uncle-dev-setup.yaml`)
- `skills/uncle-dev-spec-driven-development/SKILL.md:65-172` — HLD/LLD/EARS + spec-lock gate
- `skills/uncle-dev-design-architecture-docs/SKILL.md:19-116,207-218` — authorship order, segment/prefix rules, verification
- `skills/uncle-dev-planning-and-task-breakdown/SKILL.md:40-69,360-370` — story format, plan gate
- `skills/uncle-dev-next-task/SKILL.md:49-68,126-131,284-294` — acknowledge gate, ready-set ranking
- `skills/uncle-dev-initiative-map/SKILL.md` — the platform-tier map skill (stops before specs)
- `skills/uncle-dev-context-engineering/SKILL.md:77-93` + `agents-md-guide.md:9-54,73-79` — always-loaded context hierarchy
- `skills/uncle-dev-spec-annotations/SKILL.md:56-68,86-124,190-243` — `@spec`, `docs/specs/`, scanner
- `hooks/hooks.json` + `hooks/spec-coherence-guard.sh:1-8` — live enforcement layer
- `CLAUDE.md:44-46` — the two-ID-universe convention

---

## 9. Adoption design — `@spec` persistence across BMAD artifacts

*This section is design, not documentation-of-what-is. It records three decisions taken by the user on 2026-08-04 after §0.5 was fixed.*

### 9.0 The three decisions

| # | Question | Decision |
|---|---|---|
| D1 | Where does the canonical `@spec` ID registry live once BMAD directories are adopted? | **Keep `docs/specs/` alongside.** BMAD artifacts land in their native directories untouched; `docs/specs/<segment>-specs.md` stays the machine-readable EARS registry. BMAD `SPEC.md` cross-links to it. |
| D2 | How do `@spec` IDs bind to BMAD story artifacts? | **Both, with story IDs non-annotatable.** `stories.yaml` gains a `spec_ids:` field for planning traceability, but the guard still rejects story IDs appearing in `@spec` annotations — code can never annotate a transient story. |
| D3 | Deliverable | Research doc + concrete diffs to hook and skills. |

**Consequence of D1 that removes most of the anticipated work:** `hooks/spec-coherence-guard.sh:20` (`SPECS_DIR="$REPO_ROOT/docs/specs"`) and `scan-spec-coherence.py:269` (`specs_dir = os.path.join(root, "docs", "specs")`) both stay **unchanged**. Adopting BMAD's directory layout does not move the enforcement root, so the scanner needs no multi-root support and no regex change. The `[A-Z][A-Z0-9-]*-[0-9]+` ID grammar is untouched.

### 9.1 Where `@spec` appears in each BMAD artifact

BMAD's tiers (§1) are adopted as-is. The `@spec` axis is threaded through them as an **additive** field — no BMAD field is redefined.

| BMAD artifact | Tier | `@spec` obligation | Direction of truth |
|---|---|---|---|
| `docs/` kernel / project-context | A (durable) | None. Kernel is pre-spec narrative. | — |
| PRD (`bmad-prd`) | A | None. Sits above the enforcement boundary (§4.2). | — |
| `specs/spec-{slug}/SPEC.md` | B | **Cross-link required.** A `## Spec IDs` section listing the `SEG-AREA-NNN` IDs this slug distils into, each linking to `docs/specs/<segment>-specs.md`. | `docs/specs/` is authoritative; `SPEC.md` cites it |
| `stories.yaml` | B | **`spec_ids:` required** per story entry (may be `[]` for pure-refactor stories). | `docs/specs/` is authoritative; stories cite it |
| `stories/*.md` per-story files | B | None beyond inheriting the story's `spec_ids`. Transient. | — |
| Epic files (`## Epic N:` / `### Story N.M:`) | B | None. Parsed positionally by `sprint_plan.py`; adding IDs here would collide with its deterministic kebab-case key derivation (`llms-full.txt:3127-3130`). | — |
| Source + tests | — | **`@spec <ID>` mandatory, unchanged** — owner/entry point only, never helpers (`SKILL.md:86-124`). | consumes `docs/specs/` |

### 9.2 The persistence chain after adoption

The BMAD artifacts insert *above* the existing chain without breaking any link in it:

```
BMAD kernel ──▶ PRD ──▶ SPEC.md ──┐
                                  │  (distils into, cross-links)
                                  ▼
   HLD ──▶ LLD ──▶ EARS spec ──▶ Test ──▶ Code
                  (docs/specs/)   @spec    @spec
                        ▲
                        │  spec_ids: (planning only, non-annotatable)
                  stories.yaml
```

Two properties this preserves:

1. **Stability under BMAD's disposability.** BMAD Tier B is explicitly per-unit and disposable (§1). `SPEC.md` and `stories.yaml` can be deleted after a slug ships; the `SEG-AREA-NNN` IDs in `docs/specs/` and the `@spec` annotations in code survive, because neither points *into* Tier B. All BMAD→uncle-dev edges point downward into `docs/specs/`, never upward.
2. **No aliasing.** A story ID is never a spec ID. §0.5's precedent (`@debt` as a separate axis, `SKILL.md:150-188`) is followed: `spec_ids:` is a *reference* field, not a second annotation grammar.

### 9.3 Why story IDs must be non-annotatable (D2)

Under D1 this is *already* mostly true by construction: story IDs do not live in `docs/specs/`, so `spec_id_set()` never contains them and the guard blocks them as unknown. The gap is diagnostic, not enforcement — the operator sees a generic "not defined in docs/specs/" message and the plausible fix looks like "add the story ID to docs/specs/", which would be exactly wrong and would permanently pollute the registry with transient IDs.

The concrete diff therefore adds a *recognition* branch, not a new block: when a rejected ID matches a BMAD story-ID shape, the guard says so explicitly and names the right fix.

### 9.4 Residual risks

| Risk | Note |
|---|---|
| Drift between `SPEC.md` `## Spec IDs` and `docs/specs/` | Not machine-checked by this change. `SPEC.md` cross-links are prose-level; only `@spec` in code is scanner-enforced. Closing this would need the scanner to parse `specs/spec-*/SPEC.md`, which D1 explicitly declined. |
| `spec_ids: []` escape hatch | A story can opt out by declaring an empty list. This is intentional (refactor stories implement no new behavior) but is unenforced — nothing verifies the emptiness is honest. |
| BMAD's single-writer rule for `SPEC.md` | `bmad-spec` is "the only writer of `SPEC.md`" (`llms-full.txt:4155`). Adding a `## Spec IDs` section means either extending that agent's template or accepting a second writer. Unresolved. |

### 9.5 Merged on-disk layout

BMAD's three roots (§1.6) are adopted unchanged. uncle-dev's existing roots sit alongside them; no directory is renamed or absorbed.

```
<project-root>/
├── _bmad/                                  # BMAD config — unchanged
│   └── custom/
│
├── _bmad-output/                           # BMAD Tier B — DISPOSABLE
│   └── specs/
│       └── spec-checkout-refactor/
│           ├── SPEC.md                     # + ## Spec IDs  ──┐ cross-link
│           ├── stories.yaml                # + spec_ids:    ──┤ (D1/D2)
│           └── stories/                    #                  │
│               └── story-3.2-login-form.md #  transient       │
│                                                              │
├── docs/                                   # DURABLE ◀────────┘
│   ├── kernel.md                           # BMAD Tier A
│   ├── ARCHITECTURE-SPINE.md               # BMAD Tier A
│   ├── prd.md                              # BMAD Tier A
│   ├── hld/                                # uncle-dev
│   ├── lld/                                # uncle-dev
│   └── specs/                              # ◀ AUTHORITATIVE spec-ID registry
│       ├── auth-specs.md                   #   AUTH-UI-001, AUTH-API-001 …
│       └── checkout-specs.md               #   CHECKOUT-CORE-002 …
│
├── src/                                    # @spec AUTH-UI-001  (mandatory)
├── tests/                                  # @spec AUTH-UI-001  (mandatory)
│
├── .agents/uncle-dev-setup.yaml            # execution_profile: strict
├── .uncle-dev/learns/
└── .devlocal/<user>/                       # gitignored scratch
```

The load-bearing property is the arrow direction: everything in `_bmad-output/` points **into** `docs/specs/`, never the reverse. Delete `_bmad-output/` entirely and every `@spec` annotation in `src/` and `tests/` still resolves.

### 9.6 `@spec` threaded through the two levels

Overlaying the mandatory `@spec` axis on the shard/pump picture from §1.5:

```
  PLATFORM                                            enforcement
  ────────                                            boundary (§4.2)
  kernel.md · ARCHITECTURE-SPINE.md · prd.md                │
         │                                                  │  above:
         │  narrative, no spec IDs                          │  no @spec
         ▼                                                  │
  ═══════════════════════════════════════════════════════════════════
         │                                                  │  below:
         ▼                                                  │  @spec
  docs/specs/<segment>-specs.md   ◀── AUTHORITATIVE ────────┘  enforced
  AUTH-UI-001, CHECKOUT-CORE-002 …
         ▲                    ▲                    ▲
         │ cites              │ cites              │ annotates
         │                    │                    │
   SPEC.md               stories.yaml         src/ + tests/
   ## Spec IDs           spec_ids: [...]      // @spec AUTH-UI-001
   (prose)               (planning only)      (scanner-enforced)
  COMPONENT                                    CODE
```

Three consumers, one authority, and only the rightmost edge is machine-checked:

| Edge | Mechanism | Enforced by |
|---|---|---|
| `SPEC.md` → `docs/specs/` | prose cross-link | nothing (§9.4 risk 1) |
| `stories.yaml` → `docs/specs/` | `spec_ids:` reference field | nothing — planning-time only |
| `src`/`tests` → `docs/specs/` | `@spec <ID>` annotation | `hooks/spec-coherence-guard.sh` + `scanner/scan-spec-coherence.py` |

A story ID such as `story-3.2-login-form` appears **only** in the left column. It is never a valid `@spec` value — the guard blocks it under `execution_profile: strict` and names the EARS ID to use instead (§9.3).
