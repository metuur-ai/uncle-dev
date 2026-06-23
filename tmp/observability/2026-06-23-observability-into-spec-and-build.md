# Research: Weaving business-observability into the Spec and Build skills

**Date:** 2026-06-23
**Question:** Can we gently include the observability concepts from `uncle-dev-business-observability` into the **Spec** and **Build** touchpoints?
**Scope (confirmed by user):** Build skills (`uncle-dev-incremental-implementation`, `uncle-dev-source-driven-development`, `/uncle-dev-build`) + Spec phase (`uncle-dev-spec-driven-development`).

---

## Headline finding

The integration is **one-directional and unwired today.** `uncle-dev-business-observability` *claims* it runs at Spec, Task breakdown, and Build (its SKILL.md lines 82–86), but none of those skills reference it back. The link exists only in the observability skill's own prose.

```
business-observability  ──claims──►  Spec / Plan / Build
        ▲                                   │
        └────────────  (no link back)  ◄────┘
```

Evidence (`grep -rilE 'observability|measurement plan|metric.necessity|business-observability' skills/ commands/`):

| File | References observability? |
|---|---|
| `uncle-dev-spec-driven-development/SKILL.md` | **No** (zero matches) |
| `uncle-dev-source-driven-development/SKILL.md` | **No** (zero matches) |
| `commands/uncle-dev-build.md` | **No** (zero matches) |
| `uncle-dev-incremental-implementation/SKILL.md` | **No** (zero matches) |
| `uncle-dev-acknowledge`, `uncle-dev-shipping-and-launch`, `uncle-dev-deprecation-and-migration` | Yes — but only as passing list-mentions of the word "observability/metrics", **not** a wired hand-off to the skill |

So the "gentle inclusion" the user asks about is not just possible — it's the missing return edge that would make the observability skill's stated lifecycle real.

---

## What the observability skill expects at each touchpoint (its own words)

From `skills/uncle-dev-business-observability/SKILL.md`, "Where this runs in the lifecycle" (lines 82–86):

- **Spec** → "for each behavior/acceptance criterion, run the [metric-necessity] test; attach surviving specs as the **Measurement Plan**. Most criteria yield zero metrics — expected and correct."
- **Task breakdown** → "each surviving metric becomes one instrumentation subtask, owned by the implementation companion."
- **Build** → "the companion emits it; verify it actually answers its question."

The skill's product is a **Measurement Plan** (a list of technology-agnostic metric specs), and emit code is **delegated to a configured companion** via `scripts/uncle-dev-config.sh --list skills.companions.uncle-dev-business-observability path`. The default answer to "add a metric?" is **NO** — five gates must pass. This matters for "gentle": the skill is already designed to be near-zero-output most of the time.

---

## Natural hook points that already exist (as-is)

### Spec — `uncle-dev-spec-driven-development/SKILL.md`

1. **Step 1 — Elicit / Intent layer (line 50):** literally asks *"What must be observable/true when this ships?"* — today "observable" means visibility/acceptance, not telemetry. This is the closest existing surface to graft a measurement question onto.
2. **Step 4 — EARS, per-unit "Why" (lines 111–134):** each unit of work already states its intent. This is exactly the per-acceptance-criterion granularity the metric-necessity test wants to run against.
3. **Step 6 — auto-chain into planning (lines 152–168):** specs already flow `spec → /uncle-dev-plan`. A Measurement Plan, if produced, would ride this same arrow into task breakdown.
4. **Verification checklist (lines 176–181):** the place a one-line "Measurement Plan attached (or consciously empty)" check would live.

### Build — `commands/uncle-dev-build.md` + `uncle-dev-incremental-implementation/SKILL.md`

1. **Build command already has the companion mechanism.** `/uncle-dev-build` loads skills through `uncle-dev-load-skill.sh` and honors `COMPANION:` lines (Path A lines 57–65, Path B lines 104–112). The observability skill's delegation model (companion emits the metric) is the *same machinery* — so wiring it in is idiomatic, not novel.
2. **Path A step 6–7 / Path B step 5–6 (implement → verify):** the exact spot where "the companion emits it; verify it actually answers its question" would attach.
3. **Increment Checklist** (`uncle-dev-incremental-implementation` end) and the build verify steps: where a conditional "if this slice implements a metric from the Measurement Plan, confirm it answers its question" check would live.

---

## The repo's established "gentle" idiom (the pattern to copy)

The cleanest non-blocking cross-reference in the codebase is `uncle-dev-spec-driven-development` line 39, referencing `uncle-dev-grill` and `uncle-dev-ubiquitous-language`:

> "If a PRD exists at `docs/prd/<slug>.md` … use it … If requirements still live only in the user's head and this is a non-trivial feature, run `uncle-dev-grill` first … if `docs/ubiquitous-language.md` exists, read it … if the domain has meaningful terminology and no glossary exists yet, run `uncle-dev-ubiquitous-language` before writing."

That is the "gentle" template: **conditional, opt-in, self-deprecating ("most yield zero"), never a hard gate.** Any observability insertion should match this register — a sentence or a checklist line, not a new mandatory step.

---

## Verdict (user explicitly asked "can we")

**Yes, and it's low-risk** because the observability skill is already designed to output nothing most of the time. The minimal, gentle insertions that mirror the existing idiom:

1. **Spec — Step 1 Intent or Step 4:** one conditional line — *"For each acceptance criterion, if the change touches a revenue or core-journey behavior, run `uncle-dev-business-observability`'s metric-necessity gate. Most criteria yield zero metrics; attach any survivors as a Measurement Plan that flows downstream with the spec."*
2. **Spec — Verification checklist:** one line — *"Measurement Plan attached, or consciously empty."*
3. **Build — `/uncle-dev-build` Path A step 6 / Path B step 5:** one conditional line — *"If the story carries a metric from the Measurement Plan, the configured observability companion emits it; verify it answers its stated question (don't just confirm it's emitted)."*
4. **Build — Increment/verify checklist:** one conditional line mirroring #3.

Scope of change if pursued: **~4 single-line edits across 3 files**, all conditional, no new mandatory steps, no new files. This honors "gentle" and Simplicity First.

### Open decisions for the user (not resolved here)
- Whether to also wire the **Plan** skill (`uncle-dev-planning-and-task-breakdown`) so a surviving metric becomes a subtask — the skill names it (line 85) but the user scoped Plan out. The Spec→Build chain has a gap at Plan without it.
- Whether the Spec insertion goes at **Step 1 (Intent)** or **Step 4 (EARS per-unit)** — Step 4 is finer-grained and matches "per acceptance criterion"; Step 1 is earlier and lighter.

---

## Files examined
- `skills/uncle-dev-business-observability/SKILL.md` (full)
- `skills/uncle-dev-spec-driven-development/SKILL.md` (full)
- `commands/uncle-dev-build.md` (full)
- `skills/uncle-dev-incremental-implementation/SKILL.md` (full)
- `skills/uncle-dev-source-driven-development/SKILL.md` (grep — zero observability refs)
- Cross-skill grep across `skills/` and `commands/`
